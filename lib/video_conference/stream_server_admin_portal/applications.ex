defmodule VideoConference.StreamServerAdminPortal.Applications do
  @moduledoc """
  The StreamServerAdminPortal Applications context.

  Manages third-party applications that integrate with the stream server,
  the API keys that authenticate them, and the stream server public keys
  that verify their signed JWTs. API key secrets are generated at
  creation, returned once as `plaintext_key`, and persisted only as a
  bcrypt hash.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias VideoConference.StreamServerAdminPortal.ApiKeySecret
  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.Repo

  alias VideoConference.StreamServerAdminPortal.StreamServers.{
    ApplicationStreamServer,
    StreamServer
  }

  alias VideoConference.StreamServerAdminPortal.Applications.{
    ApiKey,
    Application,
    ConnectionInfo,
    ApplicationDescriptionWasUpdated,
    ApplicationWasAdded,
    ApplicationWasDisabled,
    ApplicationWasEnabled,
    ApplicationWasRenamed,
    StreamServerPublicKey,
    StreamServerPublicKeyWasAdded,
    StreamServerPublicKeyWasDisabled,
    StreamServerPublicKeyWasEnabled,
    StreamServerPublicKeyWasMoved,
    StreamServerPublicKeyWasRemoved
  }

  ## Applications

  @doc """
  Returns all applications, ordered by name.

  Options:

    * `:search` — limits the list to applications whose `name` contains
      the given text (case-insensitive substring match). `nil` or `""`
      lists every application.
  """
  def list_applications(opts \\ []) do
    Application
    |> filter_by_search(Keyword.get(opts, :search))
    |> order_by([a], asc: a.name)
    |> Repo.all()
  end

  defp filter_by_search(query, search) when search in [nil, ""], do: query

  defp filter_by_search(query, search) do
    pattern = "%#{search}%"
    from a in query, where: like(a.name, ^pattern)
  end

  @doc """
  Gets a single application.

  Raises `Ecto.NoResultsError` if the application does not exist.
  """
  def get_application!(id), do: Repo.get!(Application, id)

  @doc """
  Creates an application.

  Commits the record and an `ApplicationWasAdded` event on the
  application's stream in the same transaction.
  """
  def create_application(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:application, Application.changeset(%Application{}, attrs))
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasAdded.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Renames an application.
  """
  def rename_application(id, name) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.name_changeset(application, %{"name" => name}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasRenamed.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Updates an application's description.
  """
  def edit_application_description(id, description) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.description_changeset(application, %{"description" => description}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationDescriptionWasUpdated.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Enables an application.
  """
  def enable_application(id) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.enabled_changeset(application, %{"enabled" => true}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasEnabled.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Disables an application.
  """
  def disable_application(id) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.enabled_changeset(application, %{"enabled" => false}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasDisabled.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking application changes.
  """
  def change_application(%Application{} = application, attrs \\ %{}) do
    Application.changeset(application, attrs)
  end

  defp transaction_result({:ok, %{application: application}}), do: {:ok, application}

  defp transaction_result({:ok, %{stream_server_public_key: key}}), do: {:ok, key}

  defp transaction_result({:error, _operation, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp transaction_result({:error, _operation, error, _changes}), do: {:error, error}

  ## API keys

  @doc """
  Returns the API keys of the given application, ordered by name.
  """
  def list_api_keys(application_id) do
    Repo.all(
      from k in ApiKey,
        where: k.application_id == ^application_id,
        order_by: [asc: k.name]
    )
  end

  @doc """
  Gets a single API key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  @doc """
  Gets a single API key by its stored `prefix` (`"aak_" <> prefix_id`),
  returning `{:error, :not_found}` when no key carries the prefix.
  Disabled keys are returned — rejecting them is the caller's job.

  The `:application_enabled` filter additionally requires the key's
  owning application to be enabled: a key on a disabled application
  returns `{:error, :not_found}`, indistinguishable from an unknown
  prefix.
  """
  def get_api_key_by_prefix(prefix) when is_binary(prefix) do
    case Repo.get_by(ApiKey, prefix: prefix) do
      nil -> {:error, :not_found}
      api_key -> {:ok, api_key}
    end
  end

  def get_api_key_by_prefix(prefix, :application_enabled) when is_binary(prefix) do
    from(k in ApiKey,
      join: a in assoc(k, :application),
      where:
        k.prefix == ^prefix and
          a.enabled
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      api_key -> {:ok, api_key}
    end
  end

  @doc """
  Creates an API key with a freshly generated secret.

  Returns `{:ok, api_key}` where `api_key.plaintext_key` holds the
  generated secret — the only time it is available. Only the bcrypt hash
  is persisted.
  """
  def create_api_key(attrs \\ %{}) do
    prefix_id = Ecto.UUID.generate()
    secret = generate_api_key_secret(prefix_id)

    %ApiKey{}
    |> ApiKey.changeset(attrs)
    |> Ecto.Changeset.put_change(:prefix, ApiKeySecret.prefix("aak", prefix_id))
    |> Ecto.Changeset.put_change(:hashed_api_key, ApiKeySecret.hash(secret))
    |> Repo.insert()
    |> case do
      {:ok, api_key} -> {:ok, %{api_key | plaintext_key: secret}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Renames an API key.

  Accepts a key id or a loaded `%ApiKey{}`. Passing a loaded record
  writes against its `lock_version`, so a write attempted with a stale
  copy fails on the `lock_version` field.
  """
  def rename_api_key(key_or_id, name) do
    key_or_id
    |> fetch_api_key()
    |> ApiKey.name_changeset(%{"name" => name})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates an API key's description.

  Accepts a key id or a loaded `%ApiKey{}` — see `rename_api_key/2`.
  """
  def edit_api_key_description(key_or_id, description) do
    key_or_id
    |> fetch_api_key()
    |> ApiKey.description_changeset(%{"description" => description})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Enables an API key.

  Accepts a key id or a loaded `%ApiKey{}` — see `rename_api_key/2`.
  """
  def enable_api_key(key_or_id) do
    key_or_id
    |> fetch_api_key()
    |> ApiKey.enabled_changeset(%{"enabled" => true})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Disables an API key.

  Accepts a key id or a loaded `%ApiKey{}` — see `rename_api_key/2`.
  """
  def disable_api_key(key_or_id) do
    key_or_id
    |> fetch_api_key()
    |> ApiKey.enabled_changeset(%{"enabled" => false})
    |> Repo.update(stale_error_field: :lock_version)
  end

  defp fetch_api_key(%ApiKey{} = api_key), do: api_key
  defp fetch_api_key(id), do: get_api_key!(id)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking API key changes.
  """
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end

  @doc """
  Generates a random API key secret in the form `aak_<prefix_id>_<random>`
  where `aak` ("application api key") marks the scope and `prefix_id`
  is an independently generated id, so leaked keys are recognizable in
  logs and config scans.

  Delegates to `ApiKeySecret.generate/2`, the shared implementation both
  API key scopes use.
  """
  def generate_api_key_secret(prefix_id) do
    ApiKeySecret.generate("aak", prefix_id)
  end

  ## Stream server public keys

  @doc """
  Returns the stream server public keys of the given application,
  ordered by name.
  """
  def list_stream_server_public_keys(application_id) do
    Repo.all(
      from k in StreamServerPublicKey,
        where: k.application_id == ^application_id,
        order_by: [asc: k.name]
    )
  end

  @doc """
  Gets a single stream server public key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_stream_server_public_key!(id), do: Repo.get!(StreamServerPublicKey, id)

  @doc """
  Returns whether an enabled application with the given id exists.
  """
  def enabled_application?(application_id) do
    Repo.exists?(from a in Application, where: a.id == ^application_id and a.enabled)
  end

  @doc """
  Resolves an authenticated `aak_` credential to its application.

  The credential is the `{:application, %ApiKey{}}` tuple `ApiKeyAuth`
  assigns to `conn.assigns.api_credential`. Returns
  `{:ok, %Application{}}` when the application is enabled;
  `{:error, :unauthorized}` for any other credential and
  `{:error, :not_found}` when the application is disabled or missing —
  the caller cannot distinguish the two.
  """
  def authenticated_application({:application, %ApiKey{} = api_key}) do
    case Repo.get_by(Application, id: api_key.application_id, enabled: true) do
      nil -> {:error, :not_found}
      %Application{} = application -> {:ok, application}
    end
  end

  def authenticated_application(_credential), do: {:error, :unauthorized}

  @doc """
  Gets an enabled stream server public key by id belonging to the
  given application.

  Returns `{:error, :not_found}` when the key does not exist, is
  disabled, or belongs to a different application — the caller cannot
  distinguish these cases.
  """
  def get_enabled_stream_server_public_key(application_id, public_key_id) do
    case Repo.one(
           from k in StreamServerPublicKey,
             where: k.id == ^public_key_id and k.application_id == ^application_id and k.enabled
         ) do
      nil -> {:error, :not_found}
      key -> {:ok, key}
    end
  end

  @doc """
  Creates a stream server public key holding existing public key
  material. The record's generated UUID serves as its key id.
  """
  def create_stream_server_public_key(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(
      :stream_server_public_key,
      StreamServerPublicKey.changeset(%StreamServerPublicKey{}, attrs)
    )
    |> Multi.merge(fn %{stream_server_public_key: key} ->
      EventStore.append([StreamServerPublicKeyWasAdded.new(key)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Renames a stream server public key. The public key material is
  immutable and cannot be changed through this function.
  """
  def rename_stream_server_public_key(id, name) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.name_changeset(%{"name" => name})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates a stream server public key's description. The public key
  material is immutable and cannot be changed through this function.
  """
  def edit_stream_server_public_key_description(id, description) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.description_changeset(%{"description" => description})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Moves a stream server public key to another application. The public
  key material is immutable and cannot be changed through this
  function.

  Commits the update and a `StreamServerPublicKeyWasMoved` event on the
  key's stream in the same transaction.
  """
  def move_stream_server_public_key_to_application(id, application_id) do
    key = get_stream_server_public_key!(id)

    Multi.new()
    |> Multi.update(
      :stream_server_public_key,
      StreamServerPublicKey.application_changeset(key, %{"application_id" => application_id}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{stream_server_public_key: moved} ->
      EventStore.append([StreamServerPublicKeyWasMoved.new(key, moved)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Enables a stream server public key.

  Commits the update and a `StreamServerPublicKeyWasEnabled` event on
  the key's stream in the same transaction.
  """
  def enable_stream_server_public_key(id) do
    key = get_stream_server_public_key!(id)

    Multi.new()
    |> Multi.update(
      :stream_server_public_key,
      StreamServerPublicKey.enabled_changeset(key, %{"enabled" => true}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{stream_server_public_key: key} ->
      EventStore.append([StreamServerPublicKeyWasEnabled.new(key)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Disables a stream server public key.

  Commits the update and a `StreamServerPublicKeyWasDisabled` event on
  the key's stream in the same transaction.
  """
  def disable_stream_server_public_key(id) do
    key = get_stream_server_public_key!(id)

    Multi.new()
    |> Multi.update(
      :stream_server_public_key,
      StreamServerPublicKey.enabled_changeset(key, %{"enabled" => false}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{stream_server_public_key: key} ->
      EventStore.append([StreamServerPublicKeyWasDisabled.new(key)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Removes a stream server public key.

  Commits the delete and a `StreamServerPublicKeyWasRemoved` event on
  the key's stream in the same transaction.
  """
  def remove_stream_server_public_key(%StreamServerPublicKey{} = key) do
    changeset =
      key
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.optimistic_lock(:lock_version)

    Multi.new()
    |> Multi.delete(:stream_server_public_key, changeset, stale_error_field: :lock_version)
    |> Multi.merge(fn _changes ->
      EventStore.append([StreamServerPublicKeyWasRemoved.new(key)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream server public key
  changes.
  """
  def change_stream_server_public_key(%StreamServerPublicKey{} = key, attrs \\ %{}) do
    StreamServerPublicKey.changeset(key, attrs)
  end

  ## Assigned stream servers

  @doc """
  Returns the least-loaded stream server assigned to the application
  per country, as a `%{country => %StreamServer{}}` map.

  The query groups the application's `application_stream_servers`
  assignments by `country` at the database level and selects the row
  holding the minimum `load` per group — SQLite's bare-column rule
  makes `GROUP BY` return the row the `min()` aggregate picked (among
  rows tied on `load`, whichever row SQLite chose). `country_codes`
  limits the result to those countries; `[]` groups servers of every
  country, including servers without a `country`.
  """
  def stream_servers(
        application_id: application_id,
        country_codes: country_codes,
        min_loaded: true
      ) do
    StreamServer
    |> join(:inner, [s], j in ApplicationStreamServer, on: j.stream_server_id == s.id)
    |> where([_s, j], j.application_id == ^application_id)
    |> filter_stream_server_country(country_codes)
    |> group_by([s], s.country)
    |> select([s], %{country: s.country, min: min(s.load), server: s})
    |> Repo.all()
    |> Map.new(&{&1.country, &1.server})
  end

  defp filter_stream_server_country(query, codes) when codes in [nil, []], do: query

  defp filter_stream_server_country(query, codes) do
    from [s, _j] in query, where: s.country in ^codes
  end

  @doc """
  Returns the unique `country` codes of the stream servers assigned
  to the application, sorted alphabetically. Servers without a
  `country` contribute nothing; server `load` does not affect
  membership.
  """
  def available_countries(application_id: application_id) do
    Repo.all(
      from s in StreamServer,
        join: j in ApplicationStreamServer,
        on: j.stream_server_id == s.id,
        where: j.application_id == ^application_id and not is_nil(s.country),
        distinct: true,
        order_by: [asc: s.country],
        select: s.country
    )
  end

  @doc """
  Resolves `country_codes` — a list of lowercase ISO alpha-2 codes —
  to a list of connection info entries (`%{country_code:, url:,
  cert_hash?:}`) for the least-loaded stream server assigned to the
  application per country, one entry per requested code in request
  order. Delegates to `ConnectionInfo.execute/1`.
  """
  def connection_info(application_id: application_id, country_codes: country_codes) do
    ConnectionInfo.execute(application_id: application_id, country_codes: country_codes)
  end
end
