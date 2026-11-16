defmodule VideoConference.StreamServerAdminPortal.StreamServers do
  @moduledoc """
  The StreamServerAdminPortal StreamServers context.

  Manages the portal's registry of physical stream servers — the servers
  available to carry video, audio, and event streams — and their
  many-to-many assignment to applications.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias VideoConference.StreamServerAdminPortal.ApiKeySecret
  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.Repo

  alias VideoConference.StreamServerAdminPortal.Applications.Application

  alias VideoConference.StreamServerAdminPortal.StreamServers.{
    ApiKey,
    ApplicationStreamServer,
    StreamServer,
    StreamServerWasAdded,
    StreamServerWasAssignedToApplication,
    StreamServerWasUnassignedFromApplication
  }

  @doc """
  Returns all stream servers ordered by name, each with its assigned
  applications preloaded (ordered by name).

  Options:

    * `:application_id` — limits the list to servers assigned to the given
      application id, or to servers with no assigned application when
      `"unassigned"` is passed. `nil` or `""` lists every server.

    * `:search` — limits the list to servers whose `name` or `host`
      contains the given text (case-insensitive substring match). `nil`
      or `""` lists every server.

    * `:page` — together with `:per_page`, returns only that page of
      results. Both must be positive integers; otherwise the full
      filtered list is returned.
  """
  def list_stream_servers(opts \\ []) do
    applications = from a in Application, order_by: [asc: a.name]

    StreamServer
    |> filter_by_application(Keyword.get(opts, :application_id))
    |> filter_by_search(Keyword.get(opts, :search))
    |> order_by([s], asc: s.name)
    |> paginate(Keyword.get(opts, :page), Keyword.get(opts, :per_page))
    |> preload(applications: ^applications)
    |> Repo.all()
  end

  @doc """
  Returns the number of stream servers matching the `:application_id`
  and `:search` filters accepted by `list_stream_servers/1`.
  """
  def count_stream_servers(opts \\ []) do
    StreamServer
    |> filter_by_application(Keyword.get(opts, :application_id))
    |> filter_by_search(Keyword.get(opts, :search))
    |> Repo.aggregate(:count)
  end

  defp paginate(query, page, per_page)
       when is_integer(page) and is_integer(per_page) and page > 0 and per_page > 0 do
    query
    |> offset(^((page - 1) * per_page))
    |> limit(^per_page)
  end

  defp paginate(query, _page, _per_page), do: query

  defp filter_by_search(query, search) when search in [nil, ""], do: query

  defp filter_by_search(query, search) do
    pattern = "%#{search}%"

    from s in query,
      where: like(s.name, ^pattern) or like(s.host, ^pattern)
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

  Commits the record and a `StreamServerWasAdded` event on the
  server's stream in the same transaction.
  """
  def create_stream_server(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:stream_server, StreamServer.changeset(%StreamServer{}, attrs))
    |> Multi.merge(fn %{stream_server: stream_server} ->
      EventStore.append([StreamServerWasAdded.new(stream_server)])
    end)
    |> Repo.transaction()
    |> transaction_result()
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
  Returns an `%Ecto.Changeset{}` for tracking stream server changes.
  """
  def change_stream_server(%StreamServer{} = stream_server, attrs \\ %{}) do
    StreamServer.changeset(stream_server, attrs)
  end

  @doc """
  Assigns one application to a stream server, returning the server
  reloaded with its applications preloaded. Assigning an already
  assigned application is a no-op.

  Commits the join row, a `lock_version` bump on the server, and a
  `StreamServerWasAssignedToApplication` event on the server's stream
  in the same transaction.
  """
  def assign_application(stream_server_id, application_id) do
    stream_server = get_stream_server!(stream_server_id)

    {:ok, _changes} =
      Multi.new()
      |> Multi.insert(
        :assignment,
        %ApplicationStreamServer{
          stream_server_id: stream_server_id,
          application_id: application_id
        },
        on_conflict: :nothing
      )
      |> Multi.update(
        :stream_server,
        lock_bump_changeset(stream_server),
        stale_error_field: :lock_version,
        force: true
      )
      |> Multi.merge(fn %{stream_server: stream_server} ->
        EventStore.append([
          StreamServerWasAssignedToApplication.new(stream_server, application_id)
        ])
      end)
      |> Repo.transaction()

    {:ok, get_stream_server!(stream_server_id)}
  end

  @doc """
  Removes one application's assignment from a stream server, returning
  the server reloaded with its applications preloaded. Unassigning an
  application that is not assigned is a no-op.

  Commits the join row removal, a `lock_version` bump on the server,
  and a `StreamServerWasUnassignedFromApplication` event on the
  server's stream in the same transaction.
  """
  def unassign_application(stream_server_id, application_id) do
    stream_server = get_stream_server!(stream_server_id)

    {:ok, _changes} =
      Multi.new()
      |> Multi.delete_all(
        :assignment,
        from(j in ApplicationStreamServer,
          where:
            j.stream_server_id == ^stream_server_id and
              j.application_id == ^application_id
        )
      )
      |> Multi.update(
        :stream_server,
        lock_bump_changeset(stream_server),
        stale_error_field: :lock_version,
        force: true
      )
      |> Multi.merge(fn %{stream_server: stream_server} ->
        EventStore.append([
          StreamServerWasUnassignedFromApplication.new(stream_server, application_id)
        ])
      end)
      |> Repo.transaction()

    {:ok, get_stream_server!(stream_server_id)}
  end

  @doc """
  Returns whether the stream server is assigned to the application via
  `application_stream_servers`.
  """
  def assigned_to_application?(stream_server_id, application_id) do
    Repo.exists?(
      from j in ApplicationStreamServer,
        where:
          j.stream_server_id == ^stream_server_id and
            j.application_id == ^application_id
    )
  end

  defp lock_bump_changeset(%StreamServer{} = stream_server) do
    stream_server
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.optimistic_lock(:lock_version)
  end

  defp transaction_result({:ok, %{stream_server: stream_server}}), do: {:ok, stream_server}

  defp transaction_result({:error, _operation, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp transaction_result({:error, _operation, error, _changes}), do: {:error, error}

  ## Stream server API keys

  @doc """
  Returns the API keys of the given stream server, ordered by name.
  """
  def list_stream_server_api_keys(stream_server_id) do
    Repo.all(
      from k in ApiKey,
        where: k.stream_server_id == ^stream_server_id,
        order_by: [asc: k.name]
    )
  end

  @doc """
  Gets a single stream server API key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_stream_server_api_key!(id), do: Repo.get!(ApiKey, id)

  @doc """
  Gets a single stream server API key by its stored `prefix`
  (`"ssak_" <> prefix_id`), returning `{:error, :not_found}` when no
  key carries the prefix. Disabled keys are returned — rejecting them
  is the caller's job.
  """
  def get_stream_server_api_key_by_prefix(prefix) when is_binary(prefix) do
    case Repo.get_by(ApiKey, prefix: prefix) do
      nil -> {:error, :not_found}
      api_key -> {:ok, api_key}
    end
  end

  @doc """
  Creates a stream server API key with a freshly generated secret.

  Returns `{:ok, api_key}` where `api_key.plaintext_key` holds the
  generated secret — the only time it is available. Only the bcrypt hash
  is persisted.
  """
  def create_stream_server_api_key(attrs \\ %{}) do
    prefix_id = Ecto.UUID.generate()
    secret = ApiKeySecret.generate("ssak", prefix_id)

    %ApiKey{}
    |> ApiKey.changeset(attrs)
    |> Ecto.Changeset.put_change(:prefix, ApiKeySecret.prefix("ssak", prefix_id))
    |> Ecto.Changeset.put_change(:hashed_api_key, ApiKeySecret.hash(secret))
    |> Repo.insert()
    |> case do
      {:ok, api_key} -> {:ok, %{api_key | plaintext_key: secret}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Renames a stream server API key.

  Accepts a key id or a loaded `%ApiKey{}`. Passing a loaded record
  writes against its `lock_version`, so a write attempted with a stale
  copy fails on the `lock_version` field.
  """
  def rename_stream_server_api_key(key_or_id, name) do
    key_or_id
    |> fetch_stream_server_api_key()
    |> ApiKey.name_changeset(%{"name" => name})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates a stream server API key's description.

  Accepts a key id or a loaded `%ApiKey{}` — see
  `rename_stream_server_api_key/2`.
  """
  def edit_stream_server_api_key_description(key_or_id, description) do
    key_or_id
    |> fetch_stream_server_api_key()
    |> ApiKey.description_changeset(%{"description" => description})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Enables a stream server API key.

  Accepts a key id or a loaded `%ApiKey{}` — see
  `rename_stream_server_api_key/2`.
  """
  def enable_stream_server_api_key(key_or_id) do
    key_or_id
    |> fetch_stream_server_api_key()
    |> ApiKey.enabled_changeset(%{"enabled" => true})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Disables a stream server API key.

  Accepts a key id or a loaded `%ApiKey{}` — see
  `rename_stream_server_api_key/2`.
  """
  def disable_stream_server_api_key(key_or_id) do
    key_or_id
    |> fetch_stream_server_api_key()
    |> ApiKey.enabled_changeset(%{"enabled" => false})
    |> Repo.update(stale_error_field: :lock_version)
  end

  defp fetch_stream_server_api_key(%ApiKey{} = api_key), do: api_key
  defp fetch_stream_server_api_key(id), do: get_stream_server_api_key!(id)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream server API key
  changes.
  """
  def change_stream_server_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end
end
